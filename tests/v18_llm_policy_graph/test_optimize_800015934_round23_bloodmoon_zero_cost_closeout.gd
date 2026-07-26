extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800015934
const BLOODMOON_UID := "CSV8C_172"
const FEZANDIPITI_UID := "CSV8C_135"
const NIGHT_STRETCHER_UID := "CSV8C_183"
const GRASS_UID := "CSVE1C_GRA"

var _failures: Array[String] = []


func _initialize() -> void:
	var module = NoctowlSearchScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	var facts := _facts()

	var bench_observation := _base_observation()
	var bench_frontier: Array[Dictionary] = _annotate(module, profile, bench_observation, facts, [
		_candidate("rule:research", "route:information", "play_trainer", "CSV1C_121", "", 390.6),
		_candidate("closeout:bloodmoon", "route:develop", "play_basic_to_bench", BLOODMOON_UID, "", -100000.0),
	])
	_assert_stage(
		module,
		profile,
		facts,
		bench_frontier,
		1,
		"bloodmoon_closeout_bench",
		"profiled_bloodmoon_closeout_bench"
	)
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var bench_upgrade: Dictionary = strategy._find_module_verified_upgrade(
		bench_frontier,
		facts
	)
	_check(
		str(bench_upgrade.get("candidate_id", "")) == "closeout:bloodmoon",
		"public closeout must play Bloodmoon before Rule Research"
	)
	var filtered_bench_observation := _base_observation()
	filtered_bench_observation.own.active.erase("retreat_cost")
	var filtered_bench_frontier: Array[Dictionary] = _annotate(
		module,
		profile,
		filtered_bench_observation,
		facts,
		[
			_candidate(
				"rule:research",
				"route:information",
				"play_trainer",
				"CSV1C_121",
				"",
				390.6
			),
			_candidate(
				"closeout:bloodmoon",
				"route:develop",
				"play_basic_to_bench",
				BLOODMOON_UID,
				"",
				-100000.0
			),
		]
	)
	_assert_stage(
		module,
		profile,
		facts,
		filtered_bench_frontier,
		1,
		"bloodmoon_closeout_bench",
		"profiled_bloodmoon_closeout_bench"
	)
	var production_bench_observation := _base_observation()
	production_bench_observation.own.active.erase("retreat_cost")
	production_bench_observation.own.bench = [{
		"slot_id": "slot:7",
		"pokemon": {"uid": "CSV9C_155", "name": "Noctowl"},
		"energy_count": 0,
	}, {
		"slot_id": "slot:13",
		"pokemon": {"uid": "CSV9C_161", "name": "Fan Rotom"},
		"energy_count": 0,
	}, {
		"slot_id": "slot:16",
		"pokemon": {"uid": "CSV10C_082", "name": "Pikachu ex"},
		"energy_count": 0,
	}, {
		"slot_id": "slot:4",
		"pokemon": {"uid": "CSV9C_155", "name": "Noctowl"},
		"energy_count": 0,
	}, {
		"slot_id": "slot:9",
		"pokemon": {"uid": "CSV8C_028", "name": "Teal Mask Ogerpon ex"},
		"energy_count": 2,
	}]
	production_bench_observation.own.erase("discard_counts")
	production_bench_observation.own.discard = [
		{"uid": "CSV8C_183", "name": "Night Stretcher", "type": "Item"},
		{"uid": "CSVE1C_GRA", "name": "Grass Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_GRA", "name": "Grass Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_LIG", "name": "Lightning Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_MET", "name": "Metal Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_PSY", "name": "Psychic Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_PSY", "name": "Psychic Energy", "type": "Basic Energy"},
		{"uid": "CSVE1C_WAT", "name": "Water Energy", "type": "Basic Energy"},
	]
	var production_snapshot: Dictionary = module.visible_typed_snapshot(
		production_bench_observation,
		facts,
		profile,
		{}
	)
	_check(
		str(production_snapshot.get("bloodmoon_closeout_stage", "")) == "bench",
		"the exact five-Bench production projection must keep the Bloodmoon closeout live"
	)

	var recover_observation := _base_observation()
	_move_bloodmoon_to_bench(recover_observation)
	var recover_frontier: Array[Dictionary] = _annotate(module, profile, recover_observation, facts, [
		_candidate("rule:research", "route:information", "play_trainer", "CSV1C_121", "", 390.6),
		_candidate("closeout:night", "route:recover", "play_trainer", NIGHT_STRETCHER_UID, "", 322.4),
	])
	_assert_stage(
		module,
		profile,
		facts,
		recover_frontier,
		1,
		"bloodmoon_closeout_recover_energy",
		"profiled_bloodmoon_closeout_recover_energy"
	)
	var energy := _card(GRASS_UID, "Basic Energy", "Grass Energy", 401)
	var pokemon := _card("CSV9C_175", "Pokemon", "Terapagos ex", 402)
	var recovery_override: Dictionary = module.pick_verified_bloodmoon_closeout_override(
		[pokemon, energy],
		{"id": "night_stretcher_choice", "min_select": 1, "max_select": 1},
		[pokemon],
		recover_observation,
		profile,
		"bloodmoon_closeout_recover_energy"
	)
	_check(
		bool(recovery_override.get("handled", false)) \
			and recovery_override.get("items", []) == [energy],
		"Night Stretcher must recover the exact public Basic Energy, not a Pokemon"
	)
	var normalized_recovery_override: Dictionary = \
		module.pick_verified_bloodmoon_closeout_override(
			[pokemon, energy],
			{"id": "night_stretcher_choice", "max_select": 1},
			[pokemon],
			recover_observation,
			profile,
			"bloodmoon_closeout_recover_energy"
		)
	_check(
		bool(normalized_recovery_override.get("handled", false)) \
			and normalized_recovery_override.get("items", []) == [energy],
		"runtime-normalized optional Night Stretcher step must keep the exact energy target"
	)

	var attach_observation := recover_observation.duplicate(true)
	attach_observation.own.hand = attach_observation.own.hand.filter(
		func(card: Dictionary) -> bool:
			return str(card.get("uid", "")).to_upper() != NIGHT_STRETCHER_UID
	)
	attach_observation.own.hand.append({
		"uid": GRASS_UID,
		"name": "Grass Energy",
		"type": "Basic Energy",
		"energy_provides": "G",
	})
	var attach_frontier: Array[Dictionary] = _annotate(module, profile, attach_observation, facts, [
		_candidate("rule:research", "route:information", "play_trainer", "CSV1C_121", "", 390.6),
		_candidate("closeout:attach", "route:energy_commit", "attach_energy", GRASS_UID, "slot:active", -1800.0),
		_candidate("wrong:attach", "route:energy_commit", "attach_energy", GRASS_UID, "slot:ogerpon", -1700.0),
	])
	_assert_stage(
		module,
		profile,
		facts,
		attach_frontier,
		1,
		"bloodmoon_closeout_attach_pivot",
		"profiled_bloodmoon_closeout_attach_pivot"
	)
	_check(
		not bool(_annotation(attach_frontier[2]).get("verified_advantage", false)),
		"closeout energy must bind the exact Active retreat payer"
	)

	var retreat_observation := attach_observation.duplicate(true)
	retreat_observation.own.active.energy_count = 1
	retreat_observation.own.active.energy = [{
		"uid": GRASS_UID,
		"name": "Grass Energy",
		"type": "Basic Energy",
		"energy_provides": "G",
	}]
	retreat_observation.own.hand = retreat_observation.own.hand.filter(
		func(card: Dictionary) -> bool:
			return str(card.get("uid", "")).to_upper() != GRASS_UID
	)
	var retreat_frontier: Array[Dictionary] = _annotate(module, profile, retreat_observation, facts, [
		_candidate("rule:end", "route:end_turn", "end_turn", "", "", -1024.0),
		_candidate("closeout:retreat", "route:pivot", "retreat", "", "slot:bloodmoon", -7000.0),
		_candidate("wrong:retreat", "route:pivot", "retreat", "", "slot:noctowl", -6900.0),
	])
	_assert_stage(
		module,
		profile,
		facts,
		retreat_frontier,
		1,
		"bloodmoon_closeout_retreat_finisher",
		"profiled_bloodmoon_closeout_retreat_finisher"
	)
	_check(
		not bool(_annotation(retreat_frontier[2]).get("verified_advantage", false)),
		"closeout retreat must bind the exact Bloodmoon slot"
	)

	var no_energy_discard := _base_observation()
	no_energy_discard.own.discard_counts = {"CSV1C_112": 1}
	var blocked: Array[Dictionary] = _annotate(module, profile, no_energy_discard, facts, [
		_candidate("rule:research", "route:information", "play_trainer", "CSV1C_121", "", 390.6),
		_candidate("closeout:bloodmoon", "route:develop", "play_basic_to_bench", BLOODMOON_UID, "", -100000.0),
	])
	_check(
		not bool(_annotation(blocked[1]).get("verified_advantage", false)),
		"Bloodmoon suffix must fail closed without a public discarded Basic Energy"
	)

	if _failures.is_empty():
		print("V18CPG 800015934 round23 Bloodmoon zero-cost closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800015934 round23 Bloodmoon zero-cost closeout: FAIL (%d)" % _failures.size())
	quit(1)


func _base_observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 1,
			"deck_count": 10,
			"active": {
				"slot_id": "slot:active",
				"pokemon": {"uid": FEZANDIPITI_UID, "name": "Fezandipiti ex"},
				"energy_count": 0,
				"energy": [],
				"remaining_hp": 40,
				"retreat_cost": 1,
			},
			"bench": [{
				"slot_id": "slot:noctowl",
				"pokemon": {"uid": "CSV9C_155", "name": "Noctowl"},
				"energy_count": 0,
			}, {
				"slot_id": "slot:ogerpon",
				"pokemon": {"uid": "CSV8C_028", "name": "Teal Mask Ogerpon ex"},
				"energy_count": 2,
			}],
			"hand": [{
				"uid": BLOODMOON_UID,
				"name": "Bloodmoon Ursaluna ex",
				"type": "Pokemon",
			}, {
				"uid": NIGHT_STRETCHER_UID,
				"name": "Night Stretcher",
				"type": "Item",
			}, {
				"uid": "CSV1C_121",
				"name": "Professor's Research",
				"type": "Supporter",
			}],
			"discard_counts": {
				GRASS_UID: 2,
				"CSVE1C_MET": 1,
			},
		},
		"opponent": {
			"prizes_remaining": 1,
			"active": {
				"slot_id": "slot:opponent",
				"pokemon": {"uid": "CSV6C_051", "name": "Iron Hands ex"},
				"remaining_hp": 230,
				"prize_count": 2,
			},
			"bench": [],
		},
		"turn": {
			"quotas": {
				"energy_available": true,
				"retreat_available": true,
			},
		},
		"legal_actions": [],
	}


func _move_bloodmoon_to_bench(observation: Dictionary) -> void:
	observation.own.hand = observation.own.hand.filter(
		func(card: Dictionary) -> bool:
			return str(card.get("uid", "")).to_upper() != BLOODMOON_UID
	)
	observation.own.bench.append({
		"slot_id": "slot:bloodmoon",
		"pokemon": {"uid": BLOODMOON_UID, "name": "Bloodmoon Ursaluna ex"},
		"energy_count": 0,
		"energy": [],
		"remaining_hp": 260,
	})


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false},
		"turn": {
			"energy_available": true,
			"retreat_available": true,
		},
		"resources": {
			"prizes_remaining": 1,
			"energy_on_board": 2,
		},
	}


func _candidate(
	id: String,
	route_id: String,
	kind: String,
	card_uid: String,
	target: String,
	score: float
) -> Dictionary:
	var action_ref := {}
	if card_uid != "":
		action_ref["card"] = {
			"uid": card_uid,
			"name": card_uid,
			"type": "Basic Energy" if card_uid.begins_with("CSVE1C_") else "Item",
		}
	if target != "":
		action_ref["target"] = target
	return {
		"candidate_id": id,
		"route_id": route_id,
		"action_kind": kind,
		"action_ref": action_ref,
		"action_semantic_roles": ["item"],
		"checkpoint_after": "terminal" if kind == "end_turn" else "action_resolved",
		"base_score": score,
		"outcome": {"terminal": kind == "end_turn"},
	}


func _annotate(
	module: RefCounted,
	profile: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary]
) -> Array[Dictionary]:
	observation.legal_actions = []
	for candidate: Dictionary in frontier:
		if str(candidate.get("action_kind", "")) == "end_turn":
			continue
		var action := {
			"id": str(candidate.get("candidate_id", "")),
			"kind": str(candidate.get("action_kind", "")),
		}
		var action_ref: Dictionary = candidate.get("action_ref", {})
		if action_ref.get("card", {}) is Dictionary:
			action["card"] = action_ref.get("card", {}).duplicate(true)
		if str(action_ref.get("target", "")) != "":
			action["target"] = str(action_ref.get("target", ""))
		candidate["safe_prefix_action_id"] = str(candidate.get("candidate_id", ""))
		observation.legal_actions.append(action)
	return module.annotate_frontier_v2(frontier, observation, facts, profile, {})


func _assert_stage(
	module: RefCounted,
	profile: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	index: int,
	expected_kind: String,
	expected_certificate: String
) -> void:
	var annotation := _annotation(frontier[index])
	_check(
		bool(annotation.get("verified_advantage", false)) \
			and str(annotation.get("verified_advantage_kind", "")) == expected_kind,
		"%s must annotate the exact public checkpoint" % expected_kind
	)
	var advantage: Dictionary = module.verify_route_advantage(
		frontier[index],
		frontier[0],
		facts,
		profile
	)
	_check(
		bool(advantage.get("verified", false)) \
			and str(advantage.get("certificate_kind", "")) == expected_certificate,
		"%s must expose its independent public certificate" % expected_kind
	)


func _annotation(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("tera_noctowl_search", {})


func _card(uid: String, card_type: String, name_en: String, instance_id: int) -> CardInstance:
	var data := CardData.new()
	data.name = name_en
	data.name_en = name_en
	data.card_type = card_type
	var parts := uid.split("_", false, 1)
	data.set_code = parts[0]
	data.card_index = parts[1]
	var card := CardInstance.create(data, 0)
	card.instance_id = instance_id
	return card


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
