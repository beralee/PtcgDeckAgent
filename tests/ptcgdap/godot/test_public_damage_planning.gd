class_name TestPublicDamagePlanning
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd")
const TransactionJournalScript = preload("res://scripts/ai/ptcgdap/public/SemanticTransactionJournal.gd")

const GRIMMSNARL := "CSV10C_148"
const FROSLASS := "CSV7C_059"
const MUNKIDORI := "CSV8C_094"
const OGERPON := "CSV8C_028"
const LEAFEON_EX := "CSV9.5C_006"
const DEFIANCE_BAND := "CSV1C_117"
const DARK := "CSVE1C_DAR"


func test_compiled_damage_plan_is_hash_bound_and_stays_below_50ms_p95() -> String:
	var runtime_script: GDScript = load(
		"res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd"
	)
	var method_names: Array = runtime_script.get_script_method_list().map(
		func(row: Dictionary) -> Variant: return row.get("name")
	)
	if "compile_execution_plan" not in method_names or "calculate_compiled" not in method_names:
		return "missing sealed public damage execution plan"
	var policy_hash := "E".repeat(64)
	var compiled: Dictionary = runtime_script.call(
		"compile_execution_plan", policy_hash, _plans(), _transactions()
	)
	if not bool(compiled.get("accepted", false)):
		return "damage execution plan compile rejected: %s" % compiled
	var plan_hash := str(compiled.get("execution_plan_hash", ""))
	var frame := _frame(false, 201)
	for _warmup: int in 10:
		var warmup: Dictionary = runtime_script.call(
			"calculate_compiled", frame, policy_hash, plan_hash
		)
		if not bool(warmup.get("accepted", false)):
			return "compiled damage warmup rejected: %s" % warmup
	var samples_usec: Array[int] = []
	for _sample: int in 100:
		var started := Time.get_ticks_usec()
		var decision: Dictionary = runtime_script.call(
			"calculate_compiled", frame, policy_hash, plan_hash
		)
		samples_usec.append(Time.get_ticks_usec() - started)
		if decision.get("options", {}).get("0", {}).get("projected_damage") != 180:
			return "compiled damage semantics changed: %s" % decision
	samples_usec.sort()
	var p95_usec := samples_usec[int(floor(float(samples_usec.size() - 1) * 0.95))]
	print("PUBLIC_DAMAGE_COMPILED_PERF samples=100 p95_usec=%d" % p95_usec)
	if p95_usec >= 50000:
		return "compiled damage P95 exceeded 50ms: %dus" % p95_usec
	var mismatch: Dictionary = runtime_script.call(
		"calculate_compiled", frame, "F".repeat(64), plan_hash
	)
	if mismatch.get("error_code") != "damage_execution_plan_binding_mismatch":
		return "compiled damage policy mismatch did not fail closed: %s" % mismatch
	return ""


func test_registry_damage_plan_and_transaction_are_public_and_deterministic() -> String:
	var registry := RuntimeScript.load_default_registry()
	if not RuntimeScript.validate_registry(registry):
		var raw_file := FileAccess.open(RuntimeScript.REGISTRY_PATH, FileAccess.READ)
		var raw_registry: Dictionary = JSON.parse_string(raw_file.get_as_text())
		var hash_payload := raw_registry.duplicate(true)
		var expected := str(hash_payload.get("registry_sha256", ""))
		hash_payload.erase("registry_sha256")
		return "public damage registry failed integrity: loaded=%s expected=%s actual=%s" % [
			not registry.is_empty(), expected, RuntimeScript._canonical_sha256(hash_payload),
		]
	var grimmsnarl: Dictionary = registry.get("cards", {}).get(GRIMMSNARL, {})
	if grimmsnarl.get("effect_id") != "863479acd128e1e5e2643a3a1e77ce26" \
		or "attack.fixed_split.v1" not in grimmsnarl.get("capability_ids", []) \
		or grimmsnarl.has("name"):
		return "registry is not effect-bound and name-free: %s" % grimmsnarl
	var frame := _frame(false, 201)
	var plans := _plans()
	var damage: Dictionary = RuntimeScript.calculate(frame, plans, registry)
	if not bool(damage.get("accepted", false)):
		return "damage plan rejected: %s" % damage
	if damage.get("facts", {}).get("damage.available_mover_count") != 0 \
		or damage.get("facts", {}).get("damage.best_transfer_count") != 0 \
		or damage.get("facts", {}).get("damage.froslass_check_count") != 2 \
		or damage.get("options", {}).get("0", {}).get("projected_damage") != 180 \
		or damage.get("options", {}).get("0", {}).get("remaining_debt") != 30:
		return "damage plan mismatch: %s" % damage
	var journal := TransactionJournalScript.new(
		"match-1", 0, "package-identity"
	)
	var started: Dictionary = journal.advance(frame, _transactions(), damage)
	if started.get("event") != "start" \
		or started.get("state", {}).get("target_entity_serial") != 900:
		return "transaction did not start: %s" % started
	var evolved := _frame(false, 999)
	evolved["sequence"] = 2
	var continued: Dictionary = journal.advance(
		evolved, _transactions(), RuntimeScript.calculate(evolved, plans, registry)
	)
	if continued.get("event") not in ["continue", "replan"] \
		or continued.get("state", {}).get("target_entity_serial") != 900:
		return "top-card change broke entity transaction: %s" % continued
	var hidden := frame.duplicate(true)
	hidden["private_state"] = {"deck_order": [OGERPON]}
	var rejected: Dictionary = RuntimeScript.calculate(hidden, plans, registry)
	if rejected.get("error_code") != "private_damage_plan_input":
		return "hidden input did not fail closed: %s" % rejected
	return ""


func test_ready_bench_heal_is_public_response_risk_but_unready_heal_is_not() -> String:
	var registry := RuntimeScript.load_default_registry()
	var leafeon: Dictionary = registry.get("cards", {}).get(LEAFEON_EX, {})
	if "attack.bench_heal.v1" not in leafeon.get("capability_ids", []):
		return "Leafeon bench-heal capability is missing: %s" % leafeon
	var frame := _frame(false, 201)
	frame["public_state"]["opponent"]["active"] = [
		_slot(900, 901, LEAFEON_EX, 260, 270, 2, 0, ["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"]),
	]
	frame["public_state"]["opponent"]["bench"] = [
		_slot(910, 911, OGERPON, 100, 210, 2),
	]
	frame["options"] = [
		_option(0, "use_ability", {
			"source_uid": MUNKIDORI, "source_entity_serial": 130, "ability_index": 0,
		}),
	]
	var ready: Dictionary = RuntimeScript.calculate(frame, _plans(), registry)
	if not bool(ready.get("accepted", false)) \
		or int(ready.get("targets", {}).get("910", {}).get("response_risk", 0)) < 100:
		return "ready bench heal did not add public response risk: %s" % ready
	var unready := frame.duplicate(true)
	unready["source"]["window_id"] = "E".repeat(64)
	unready["public_state"]["opponent"]["active"][0]["attached_energy_uids"] = [
		"CSVE1C_GRA", "CSVE1C_WAT",
	]
	unready["public_state"]["opponent"]["active"][0]["attached_energy_count"] = 2
	var result: Dictionary = RuntimeScript.calculate(unready, _plans(), registry)
	if int(result.get("targets", {}).get("910", {}).get("response_risk", 0)) >= 100:
		return "unready bench heal still added response risk: %s" % result
	return ""


func test_transfer_plan_counts_only_current_legal_movers_and_finishes_easy_ko() -> String:
	var registry := RuntimeScript.load_default_registry()
	var frame := _frame(false, 201)
	frame["public_state"]["self"]["bench"].append(
		_slot(131, 132, MUNKIDORI, 80, 110, 1, 30, [DARK])
	)
	frame["public_state"]["self"]["bench"].append(
		_slot(132, 133, MUNKIDORI, 80, 110, 1, 30, [DARK])
	)
	frame["public_state"]["opponent"]["active"] = [
		_slot(900, 901, LEAFEON_EX, 260, 270, 2, 0, ["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"]),
	]
	frame["public_state"]["opponent"]["bench"] = [
		_slot(910, 911, OGERPON, 100, 210, 2),
		_slot(920, 921, OGERPON, 70, 210, 1),
	]
	frame["options"] = []
	for entity_serial: int in [130, 131, 132]:
		frame["options"].append(_option(frame["options"].size(), "use_ability", {
			"source_uid": MUNKIDORI,
			"source_entity_serial": entity_serial,
			"ability_index": 0,
		}))
	var result: Dictionary = RuntimeScript.calculate(frame, _plans(), registry)
	var facts: Dictionary = result.get("facts", {})
	if not bool(result.get("accepted", false)) \
		or facts.get("damage.available_mover_count") != 3 \
		or facts.get("damage.best_transfer_target_entity_serial") != 920 \
		or facts.get("damage.best_transfer_attack_windows_to_ko") != 1:
		return "legal mover/easy KO planning mismatch: %s" % result
	return ""


func test_current_attack_exposes_exact_two_prize_gust_target() -> String:
	var registry := RuntimeScript.load_default_registry()
	var frame := _frame(true, 201)
	frame["public_state"]["opponent"]["active"] = [
		_slot(900, 901, LEAFEON_EX, 260, 270, 2, 0, ["CSVE1C_GRA", "CSVE1C_WAT", "CSVE1C_COL"]),
	]
	frame["public_state"]["opponent"]["bench"] = [
		_slot(910, 911, OGERPON, 210, 210, 2),
	]
	frame["options"] = [
		_option(0, "attack", {
			"source_uid": GRIMMSNARL, "source_serial": 101,
			"source_entity_serial": 100, "attack_index": 0, "projected_damage": 210,
		}),
		_option(1, "play_trainer", {"card_uid": "CSV6C_114"}),
		_option(2, "play_trainer", {"card_uid": "CSVH1aC_023"}),
	]
	var result: Dictionary = RuntimeScript.calculate(frame, _plans(), registry)
	var facts: Dictionary = result.get("facts", {})
	if not bool(result.get("accepted", false)) \
		or result.get("options", {}).get("0", {}).get("attack_windows_to_ko") != 2 \
		or facts.get("damage.current_attack_damage") != 210 \
		or facts.get("damage.best_gust_target_entity_serial") != 910 \
		or facts.get("damage.best_gust_attack_windows_to_ko") != 1 \
		or facts.get("damage.best_gust_prize_yield") != 2:
		return "exact gust planning mismatch: %s" % result
	return ""


func test_defiance_flip_and_semantic_reorder_match_python_contract() -> String:
	var registry := RuntimeScript.load_default_registry()
	var plans := _plans()
	var behind: Dictionary = RuntimeScript.calculate(_frame(true, 201), plans, registry)
	var even_frame := _frame(false, 201)
	var even: Dictionary = RuntimeScript.calculate(even_frame, plans, registry)
	if behind.get("options", {}).get("0", {}).get("projected_damage") != 210 \
		or behind.get("options", {}).get("0", {}).get("overkill") != 0 \
		or even.get("options", {}).get("0", {}).get("projected_damage") != 180:
		return "defiance metamorphic flip mismatch: %s / %s" % [behind, even]
	var reordered := even_frame.duplicate(true)
	reordered["source"]["window_id"] = "C".repeat(64)
	reordered["options"].reverse()
	for index: int in reordered.get("options", []).size():
		reordered["options"][index]["index"] = index
	var moved: Dictionary = RuntimeScript.calculate(reordered, plans, registry)
	if even.get("facts") != moved.get("facts") \
		or even.get("options", {}).get("0") != moved.get("options", {}).get("1") \
		or even.get("audit_hash") == moved.get("audit_hash"):
		return "semantic reorder did not preserve route: %s" % moved
	return ""


func test_current_attack_option_post_modifier_zero_damage_is_authoritative() -> String:
	var registry := RuntimeScript.load_default_registry()
	var blocked := _frame(false, 201)
	blocked["public_state"]["opponent"]["bench"] = [
		_slot(910, 911, OGERPON, 210, 210, 2),
	]
	blocked["options"][0]["projected_damage"] = 0
	var result: Dictionary = RuntimeScript.calculate(blocked, _plans(), registry)
	var metrics: Dictionary = result.get("options", {}).get("0", {})
	if not bool(result.get("accepted", false)) \
		or metrics.get("projected_damage") != 0 \
		or metrics.get("bench_damage") != 30 \
		or result.get("facts", {}).get("damage.current_attack_bench_damage") != 30 \
		or metrics.get("attack_windows_to_ko") != 3 \
		or metrics.get("remaining_debt") != 210:
		return "post-modifier zero damage was ignored: %s" % result
	var unblocked := blocked.duplicate(true)
	unblocked["source"]["window_id"] = "D".repeat(64)
	unblocked["options"][0]["projected_damage"] = 180
	var restored: Dictionary = RuntimeScript.calculate(unblocked, _plans(), registry)
	if restored.get("options", {}).get("0", {}).get("projected_damage") != 180 \
		or restored.get("options", {}).get("0", {}).get("remaining_debt") != 30:
		return "post-modifier damage restoration mismatch: %s" % restored
	return ""


func test_own_side_tool_target_does_not_become_a_damage_plan_target() -> String:
	var registry := RuntimeScript.load_default_registry()
	var frame := _frame(false, 201)
	var own_active: Dictionary = frame["public_state"]["self"]["active"][0]
	frame["prompt_kind"] = "main"
	frame["source"]["window_id"] = "E".repeat(64)
	frame["options"] = [
		_option(0, "attach_tool", {
			"card_uid": "CSV5C_120",
			"target_uid": own_active.get("local_card_uid"),
			"target_serial": own_active.get("serial"),
			"target_entity_serial": own_active.get("entity_serial"),
		}),
		_option(1, "end_turn", {"option_type_raw": 14}),
	]
	var result: Dictionary = RuntimeScript.calculate(frame, _plans(), registry)
	if not bool(result.get("accepted", false)) \
		or result.get("facts", {}).get("damage.best_target_entity_serial") != 900 \
		or result.get("facts", {}).get("damage.best_remaining_debt") != 210 \
		or result.get("targets", {}).has(str(own_active.get("entity_serial"))) \
		or result.get("options", {}).get("0", {}).get("target_entity_serial") != null:
		return "own-side tool target leaked into damage planning: %s" % result
	return ""


func test_transaction_template_priority_and_energy_debt_match_python_contract() -> String:
	var registry := RuntimeScript.load_default_registry()
	var frame := _frame(false, 201)
	frame["public_state"]["self"]["bench"].append(
		_slot(140, 141, GRIMMSNARL, 320, 320, 2, 0, [DARK])
	)
	var damage: Dictionary = RuntimeScript.calculate(frame, _plans(), registry)
	var journal := TransactionJournalScript.new("match-templates", 0, "package-identity")
	var started: Dictionary = journal.advance(frame, _three_transactions(), damage)
	if started.get("state", {}).get("transaction_id") != "backup-grimmsnarl-ready" \
		or started.get("state", {}).get("target_entity_serial") != 140 \
		or started.get("state", {}).get("remaining_energy_debt") != 1:
		return "transaction template selection mismatch: %s" % started
	var funded := frame.duplicate(true)
	funded["sequence"] = 2
	funded["source"]["window_id"] = "D".repeat(64)
	var target: Dictionary = funded["public_state"]["self"]["bench"][-1]
	target["attached_energy_count"] = 2
	target["attached_energy_uids"] = [DARK, DARK]
	target["energy_debt"] = 0
	target["attack_ready"] = true
	var completed: Dictionary = journal.advance(
		funded, _three_transactions(), RuntimeScript.calculate(funded, _plans(), registry)
	)
	if completed.get("event") != "complete" \
		or completed.get("state", {}).get("remaining_energy_debt") != 0:
		return "energy transaction did not complete: %s" % completed
	return ""


func _slot(
	entity_serial: int,
	card_serial: int,
	uid: String,
	remaining_hp: int,
	max_hp: int,
	prize_value: int,
	damage_counters: int = 0,
	energy_uids: Array = [],
	tool_uid: Variant = null
) -> Dictionary:
	return {
		"serial": card_serial,
		"entity_serial": entity_serial,
		"local_card_uid": uid,
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"damage_counters": damage_counters,
		"prize_value": prize_value,
		"attached_energy_count": energy_uids.size(),
		"attached_energy_uids": energy_uids.duplicate(),
		"attached_tool_uid": tool_uid,
		"pokemon_stack_uids": [uid],
		"minimum_attack_energy_count": 2,
		"attack_ready": energy_uids.size() >= 2,
		"energy_debt": maxi(0, 2 - energy_uids.size()),
	}


func _option(index: int, kind: String, updates: Dictionary = {}) -> Dictionary:
	var value := {
		"index": index, "kind": kind, "card_uid": null, "card_serial": null,
		"source_uid": null, "source_serial": null, "source_entity_serial": null,
		"target_uid": null, "target_serial": null, "target_entity_serial": null,
		"target_remaining_hp": null, "target_prize_value": null,
		"target_attached_energy_count": null, "target_attached_energy_uids": null,
		"target_minimum_attack_energy_count": null, "target_attack_ready": null,
		"target_energy_debt": null, "projected_damage": null,
		"projected_knockout": false, "requires_interaction": false,
		"attack_index": null, "option_number": null, "ability_index": null,
		"energy_type_raw": null, "energy_count": null, "special_condition_type": null,
		"pending_assignment_count": 0, "tags": [],
		"option_type_raw": 13 if kind == "attack" else 3,
		"option_player_index": 0,
	}
	for key: Variant in updates:
		value[key] = updates[key]
	return value


func _frame(behind: bool, target_card_serial: int) -> Dictionary:
	var active := _slot(100, 101, GRIMMSNARL, 260, 320, 2, 60, [DARK, DARK], DEFIANCE_BAND)
	var own_bench := [
		_slot(110, 111, FROSLASS, 90, 90, 1),
		_slot(120, 121, FROSLASS, 90, 90, 1),
		_slot(130, 131, MUNKIDORI, 90, 110, 1, 20, [DARK]),
	]
	var opponent_active := _slot(
		900, target_card_serial, OGERPON, 210, 210, 2, 0, ["CSVE1C_GRA"]
	)
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": 1,
		"seat": 0,
		"prompt_kind": "main_action",
		"source": {"public_observation_hash": "A".repeat(64), "window_id": "B".repeat(64)},
		"public_state": {
			"turn_number": 8,
			"phase": "MAIN",
			"self": {
				"hand": [], "active": [active], "bench": own_bench, "discard": [],
				"deck_count": 25, "prizes_remaining": 4 if behind else 2,
			},
			"opponent": {
				"hand_count": 5, "active": [opponent_active], "bench": [], "discard": [],
				"deck_count": 24, "prizes_remaining": 2 if behind else 4,
			},
		},
		"select_semantics": {
			"min_count": 1, "max_count": 1, "select_type_raw": 6, "select_context_raw": 36,
		},
		"options": [
			_option(0, "attack", {
				"source_uid": GRIMMSNARL, "source_serial": 101,
				"source_entity_serial": 100, "attack_index": 0,
			}),
			_option(1, "end_turn", {"option_type_raw": 14}),
		],
	}


func _plans() -> Array:
	return [{
		"plan_id": "ogerpon-prize-map",
		"goal_id": "take-two-prize-knockout",
		"priority": 0,
		"horizon_attack_windows": 2,
		"capability_ids": [
			"attack.fixed_split.v1", "between_turn.ability_counter.v1",
			"ability.move_damage_counters.v1", "tool.conditional_active_damage_bonus.v1",
			"attack.mass_devolution.v1", "attack.bench_heal.v1",
		],
		"target_roles": ["opponent.active", "opponent.bench"],
		"objective_order": [
			"attack_windows", "prize_yield", "remaining_debt", "overkill", "response_risk",
		],
	}]


func _transactions() -> Array:
	return [{
		"transaction_id": "ogerpon-two-prize-conversion",
		"goal_id": "take-two-prize-knockout",
		"priority": 0,
		"max_own_turns": 2,
		"target_role": "opponent.pokemon",
		"start_when": [], "continue_when": [],
		"success_when": [{
			"fact": "transaction.remaining_damage_debt", "op": "eq", "value": 0,
			"card_uid": null,
		}],
		"abort_when": [],
		"step_prompt_kinds": ["main_action", "attack", "damage_target"],
	}]


func _three_transactions() -> Array:
	return [
		{
			"transaction_id": "devolution-finish", "goal_id": "take-two-prize-knockout",
			"priority": 20, "max_own_turns": 1, "target_role": "opponent.pokemon",
			"start_when": [{
				"fact": "self.hand.count_uid", "op": "gt", "value": 0,
				"card_uid": "CSV5C_120",
			}],
			"continue_when": [], "success_when": [], "abort_when": [],
			"step_prompt_kinds": ["main_action", "damage_target"],
		},
		{
			"transaction_id": "backup-grimmsnarl-ready", "goal_id": "take-two-prize-knockout",
			"priority": 10, "max_own_turns": 2, "target_role": "self.pokemon",
			"start_when": [
				{"fact": "transaction.candidate.card_uid", "op": "eq", "value": GRIMMSNARL, "card_uid": null},
				{"fact": "transaction.candidate.remaining_energy_debt", "op": "gt", "value": 0, "card_uid": null},
			],
			"continue_when": [{"fact": "transaction.remaining_energy_debt", "op": "gt", "value": 0, "card_uid": null}],
			"success_when": [{"fact": "transaction.remaining_energy_debt", "op": "eq", "value": 0, "card_uid": null}],
			"abort_when": [],
			"step_prompt_kinds": ["main_action", "search", "assignment_source", "assignment_target"],
		},
		{
			"transaction_id": "ogerpon-two-prize-conversion", "goal_id": "take-two-prize-knockout",
			"priority": 0, "max_own_turns": 2, "target_role": "opponent.pokemon",
			"start_when": [{"fact": "damage.best_prize_yield", "op": "eq", "value": 2, "card_uid": null}],
			"continue_when": [{"fact": "transaction.remaining_damage_debt", "op": "gt", "value": 0, "card_uid": null}],
			"success_when": [{"fact": "transaction.remaining_damage_debt", "op": "eq", "value": 0, "card_uid": null}],
			"abort_when": [{"fact": "opponent.prizes_remaining", "op": "eq", "value": 0, "card_uid": null}],
			"step_prompt_kinds": ["main_action", "attack", "damage_target"],
		},
	]
